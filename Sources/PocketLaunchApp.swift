import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import ImageIO

struct Game: Identifiable, Codable {
    var id = UUID()
    var name: String
    var launchURL: String
    var favorite = false
    var artwork: Data?
    var automaticArtworkDisabled: Bool?
}

@MainActor final class Library: ObservableObject {
    @Published var games: [Game] = []
    @Published var files: [URL] = []
    @Published var importNotice: String?
    @Published var artworkStatuses: [UUID: String] = [:]
    let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    var archive: URL { root.appendingPathComponent("IPAs", isDirectory: true) }
    var index: URL { root.appendingPathComponent("games.json") }
    init() {
        games = (try? JSONDecoder().decode([Game].self, from: Data(contentsOf: index))) ?? []
        refresh()
    }
    func resolveMissingArtwork() async {
        let pending = games.filter { $0.artwork == nil && $0.automaticArtworkDisabled != true }
        for game in pending {
            guard !Task.isCancelled else { return }
            artworkStatuses[game.id] = "Finding artwork…"
            do {
                let data = try await AutomaticArtwork.shared.artwork(launchURL: game.launchURL, localFiles: files)
                try Task.checkCancellation()
                guard let index = games.firstIndex(where: { $0.id == game.id }),
                      games[index].artwork == nil, games[index].automaticArtworkDisabled != true else { continue }
                games[index].artwork = data
                do { try save() }
                catch { games[index].artwork = nil; throw error }
                artworkStatuses[game.id] = nil
            } catch is CancellationError {
                artworkStatuses[game.id] = nil
                return
            } catch {
                artworkStatuses[game.id] = (error as? AutomaticArtworkError)?.errorDescription
                    ?? "Couldn’t load artwork. Long-press to retry."
            }
        }
    }
    func save() throws { try JSONEncoder().encode(games).write(to: index, options: .atomic) }
    func refresh() {
        files = ((try? FileManager.default.contentsOfDirectory(at: archive, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension.lowercased() == "ipa" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
    func importFiles(_ urls: [URL]) async throws {
        importNotice = nil
        let destination = archive
        let imported = try await Task.detached(priority: .userInitiated) {
            var imported: [(IPAIconMetadata, Data)] = []
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            for url in urls {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard url.pathExtension.lowercased() == "ipa" else { continue }
                let target = destination.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
                var coordinationError: NSError?
                var copyError: Error?
                NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
                    do { try FileManager.default.copyItem(at: readable, to: target) }
                    catch { copyError = error }
                }
                if let error = coordinationError { throw error }
                if let error = copyError { throw error }
                if let metadata = try? IPAIconReader.read(target),
                   let artwork = try? IPAIconImage.artwork(from: metadata) {
                    imported.append((metadata, artwork))
                }
            }
            return imported
        }.value
        let previous = games
        var filled = 0
        for (metadata, artwork) in imported {
            for index in games.indices where games[index].artwork == nil && metadata.matches(launchURL: games[index].launchURL) {
                games[index].artwork = artwork
                filled += 1
            }
        }
        do { if filled > 0 { try save() } }
        catch { games = previous; refresh(); throw error }
        importNotice = filled > 0
            ? "IPA imported. Game icons added to \(filled) game\(filled == 1 ? "" : "s")."
            : "IPA imported. To use its icon for an existing game, long-press the game, choose Change artwork, then Use icon from IPA."
        refresh()
    }
}

@main struct PocketLaunchApp: App {
    @StateObject private var library = Library()
    var body: some Scene { WindowGroup { rootView.preferredColorScheme(.dark) } }

    @ViewBuilder private var rootView: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--preview-cartridge") {
            let artwork = Bundle.main.url(forResource: "010095300B6A4000", withExtension: "jpg")
                .flatMap { try? Data(contentsOf: $0) }
            CartridgeLaunchView(
                game: Game(name: "South Park", launchURL: "preview://", artwork: artwork),
                cancel: {}, finish: {}
            )
        } else {
            LauncherView().environmentObject(library)
        }
        #else
        LauncherView().environmentObject(library)
        #endif
    }
}

struct LauncherView: View {
    @EnvironmentObject var library: Library
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var launchingGame: Game?
    @State private var artworkGame: Game?
    @State private var artworkRetry = 0
    @State private var query = ""
    @State private var addGame = false
    @State private var importing = false
    @State private var busy = false
    @State private var error: String?
    @State private var downloadURL = ""

    private var filtered: [Game] {
        library.games.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { $0.favorite != $1.favorite ? $0.favorite : $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private var artworkLookupKey: String {
        var key = String(artworkRetry) + (scenePhase == .active ? "-active" : "-inactive")
        for game in library.games { key += game.id.uuidString + game.launchURL }
        return key
    }
    private var showingError: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }
    var body: some View {
        tabs
            .tint(.mint)
            .overlay { launchOverlay }
            .task(id: artworkLookupKey) {
                if scenePhase == .active { await library.resolveMissingArtwork() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { launchingGame = nil }
            }
            .sheet(item: $artworkGame) { game in
                ArtworkEditor(game: game) { data in saveArtwork(data, for: game) }
            }
            .sheet(isPresented: $addGame) { AddGameView(add: appendGame) }
            .fileImporter(isPresented: $importing,
                          allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data],
                          allowsMultipleSelection: true,
                          onCompletion: handleImport)
            .alert("PocketLaunch", isPresented: showingError) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
    }

    private var tabs: some View {
        TabView {
            gamesTab.tabItem { Label("Games", systemImage: "gamecontroller") }
            ipasTab.tabItem { Label("IPAs", systemImage: "shippingbox") }
        }
    }

    private var gamesTab: some View {
        NavigationStack {
            CartridgeShelfView(games: filtered, onPlay: playGame) { game in gameMenu(game) }
                .navigationTitle("PocketLaunch")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search games")
                .toolbar { Button("Add game", systemImage: "plus") { addGame = true } }
        }
    }

    private var ipasTab: some View {
        NavigationStack {
            List {
                Section {
                    Button("Import IPA", systemImage: "square.and.arrow.down") { importing = true }.disabled(busy)
                    if busy { ProgressView("Importing IPAs and reading icons…") }
                    if let notice = library.importNotice {
                        Text(notice).font(.footnote).foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Files are copied into this app. Share an IPA to your installation tool, then return to Games to add its launch link.")
                }
                Section("Your IPA files") {
                    ForEach(library.files, id: \.self) { file in
                        ShareLink(item: file) {
                            Label(String(file.lastPathComponent.dropFirst(37)), systemImage: "shippingbox")
                        }
                    }
                    .onDelete(perform: deleteIPAs)
                }
                Section("Install a hosted IPA") {
                    TextField("https://…/game.ipa", text: $downloadURL)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Install with SideStore", systemImage: "arrow.up.forward.app", action: installRemote)
                }
            }.navigationTitle("IPA Library")
        }
    }

    private func playGame(_ game: Game) {
        guard launchingGame == nil else { return }
        launchingGame = game
    }

    @ViewBuilder private func gameMenu(_ game: Game) -> some View {
        Button("Change artwork", systemImage: "photo") { artworkGame = game }
        if game.artwork == nil {
            Button("Find artwork automatically", systemImage: "sparkles") { retryArtwork(game) }
        }
        Button(game.favorite ? "Unfavorite" : "Favorite", systemImage: "star") { toggleFavorite(game) }
        Button("Remove", role: .destructive) { removeGame(game) }
    }

    @ViewBuilder private var launchOverlay: some View {
        if let game = launchingGame {
            CartridgeLaunchView(game: game, cancel: { launchingGame = nil }) {
                guard launchingGame?.id == game.id else { return }
                launchingGame = nil
                launch(game.launchURL)
            }
            .id(game.id).zIndex(100)
        }
    }

    private func appendGame(_ game: Game) {
        library.games.append(game)
        persist()
    }
    private func saveArtwork(_ data: Data?, for game: Game) {
        guard let index = library.games.firstIndex(where: { $0.id == game.id }) else { return }
        let previous = library.games[index]
        library.games[index].artwork = data
        library.games[index].automaticArtworkDisabled = data == nil
        do { try library.save() }
        catch { library.games[index] = previous; self.error = error.localizedDescription }
    }
    private func retryArtwork(_ game: Game) {
        guard let index = library.games.firstIndex(where: { $0.id == game.id }) else { return }
        library.games[index].automaticArtworkDisabled = false
        persist()
        artworkRetry += 1
    }
    private func toggleFavorite(_ game: Game) {
        guard let index = library.games.firstIndex(where: { $0.id == game.id }) else { return }
        library.games[index].favorite.toggle()
        persist()
    }
    private func removeGame(_ game: Game) {
        library.games.removeAll { candidate in candidate.id == game.id }
        persist()
    }
    private func deleteIPAs(_ offsets: IndexSet) {
        for index in offsets {
            do { try FileManager.default.removeItem(at: library.files[index]) }
            catch { self.error = error.localizedDescription }
        }
        library.refresh()
    }
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            busy = true
            Task { await importIPAs(urls) }
        case .failure(let failure):
            error = failure.localizedDescription
        }
    }
    private func importIPAs(_ urls: [URL]) async {
        defer { library.refresh(); busy = false }
        do { try await library.importFiles(urls) }
        catch { self.error = error.localizedDescription }
    }
    private func persist() {
        do { try library.save() }
        catch { self.error = error.localizedDescription }
    }
    private func launch(_ value: String) {
        guard let url = URL(string: value), url.scheme != nil else {
            error = "Enter a valid game launch link."; return
        }
        openURL(url) { accepted in
            if !accepted {
                error = "This link could not be opened. Check that the game is installed and registers this launch scheme."
            }
        }
    }
    private func installRemote() {
        guard let url = URL(string: downloadURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https", url.host != nil else {
            error = "Enter an HTTPS download link for the IPA."; return
        }
        var components = URLComponents()
        components.scheme = "sidestore"
        components.host = "install"
        components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        if let link = components.url { launch(link.absoluteString) }
    }
}

struct AddGameView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var link = ""
    let add: (Game) -> Void
    var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && URL(string: link)?.scheme != nil
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Game name", text: $name)
                TextField("Launch link, such as mygame://", text: $link).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                Text("The game must register this link. An IPA filename or bundle identifier alone cannot open a game.").font(.footnote).foregroundStyle(.secondary)
            }.navigationTitle("Add game")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Add") { add(Game(name: name.trimmingCharacters(in: .whitespacesAndNewlines), launchURL: link)); dismiss() }.disabled(!valid) }
                }
        }
    }
}


struct GameArtwork: View {
    let data: Data?
    var body: some View {
        GeometryReader { geometry in
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
            } else {
                Image(systemName: "gamecontroller.fill").font(.system(size: 42)).foregroundStyle(.mint)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}

struct ArtworkEditor: View {
    @Environment(\.dismiss) private var dismiss
    let game: Game
    let save: (Data?) -> Void
    @State private var selection: PhotosPickerItem?
    @State private var choosingIPA = false
    @State private var artwork: Data?
    @State private var loading = false
    @State private var message: String?
    init(game: Game, save: @escaping (Data?) -> Void) {
        self.game = game
        self.save = save
        _artwork = State(initialValue: game.artwork)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    GameArtwork(data: artwork).frame(height: 260).clipped()
                    PhotosPicker(selection: $selection, matching: .images) {
                        Label("Choose from Photos", systemImage: "photo.on.rectangle")
                    }.disabled(loading)
                    Button("Use icon from IPA", systemImage: "shippingbox") { choosingIPA = true }
                        .disabled(loading)
                    if loading { ProgressView("Loading artwork…") }
                    if let message { Text(message).foregroundStyle(.red) }
                    if artwork != nil {
                        Button("Remove artwork", role: .destructive) { artwork = nil; selection = nil; message = nil }
                            .disabled(loading)
                    }
                } header: { Text(game.name) }
                  footer: { Text("Read the icon from your game’s IPA or choose a cover from Photos. The same artwork appears on its launch cartridge.") }
            }
            .navigationTitle("Game artwork")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(artwork); dismiss() }.disabled(loading)
                }
            }
            .fileImporter(isPresented: $choosingIPA, allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data]) { result in
                switch result {
                case .success(let url):
                    loading = true
                    message = nil
                    Task {
                        defer { loading = false }
                        do { artwork = try await IPAIconImage.read(url) }
                        catch { message = error.localizedDescription }
                    }
                case .failure(let error): message = error.localizedDescription
                }
            }
            .task(id: selection) {
                guard let selection else { return }
                loading = true
                message = nil
                defer { loading = false }
                do {
                    guard let data = try await selection.loadTransferable(type: Data.self) else {
                        message = "This photo could not be loaded."; return
                    }
                    try Task.checkCancellation()
                    let thumbnail = await Task.detached(priority: .userInitiated) {
                        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                                kCGImageSourceCreateThumbnailFromImageAlways: true,
                                kCGImageSourceThumbnailMaxPixelSize: 1000,
                                kCGImageSourceCreateThumbnailWithTransform: true
                              ] as CFDictionary)
                        else { return Optional<Data>.none }
                        return UIImage(cgImage: image).jpegData(compressionQuality: 0.85)
                    }.value
                    try Task.checkCancellation()
                    if let thumbnail { artwork = thumbnail }
                    else { message = "Choose a supported image." }
                } catch is CancellationError { }
                  catch { message = error.localizedDescription }
            }
        }
    }
}
